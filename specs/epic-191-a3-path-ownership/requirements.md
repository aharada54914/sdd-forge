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
  Feature's Facet Manifest to the entire declared ownership input, not the
  fragment a given resolve happened to consume or evaluate
  (`docs/adr/0021-context-projection-staleness.md` lines 41-42, 78-88).
- Epic A1's `contracts/project-context.template.yaml`, whose
  `shared_paths` section is the single canonical source of the default
  cross-cutting seed list (REQ-006) — A3 defines no competing list of its
  own — so that ordinary spec/report/CI changes do not trip Fail-1 on day
  one of adopting Project Context, and REQ-007's day-one integration test
  catches a regression if A1's shipped inventory ever diverges from the
  agreed six-entry set.
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
- A static, capability-state-blind required-check-set would force
  `check-component-coverage` into an impossible position once registered
  in `check-contract`'s hardcoded `high`/`critical` tier minimum
  (`check-contract.py:37-42,127-157` reads only a task's `risk`/`stack`
  descriptors, never `project-context.yaml`'s `workflow.capability_enforcement`,
  INV-018): a `disabled-legacy` high/critical task would either need a
  `passes:true` evidence entry for a check that never ran (a footgun that
  invites a fabricated pass) or be permanently unable to reach Done at all,
  and `advisory` would be silently promoted to the same blocking strength
  as `required` — both outcomes contradict ADR-0016's own
  `capability_enforcement: advisory | required` distinction and its
  `disabled-legacy` domain-exclusion rule. `check-component-coverage`
  itself is state-aware either way: it always runs, always emits real
  evidence, and its own recorded `state`/exit-code reflect which of the
  three derived states applied (REQ-004) — that half of the remedy is
  unchanged (scope note added 2026-08-11, human-directed ruling:
  "always" quantifies over the three derived states; a
  present-but-malformed config derives no state and produces no record
  — REQ-004's present-but-malformed sub-bullet, TEST-035d). **Superseded (2026-08-11, human-directed)** — the other
  half of this passage originally read: "The remedy is not to make
  `check-contract`'s tier mechanism itself capability-aware (out of this
  feature's touch surface, Non-goals)". That prohibition existed to keep
  this feature's protected-file touch surface minimal — the sanctioned
  `check-contract` edit was scoped to adding tier-minimum entries plus
  the producer-digest verification pass (Non-goals) — and it implicitly
  presupposed that every pre-existing `high`/`critical` contract could
  satisfy the newly-registered minimum through a backfilled evidence
  entry. Measurement on 2026-08-11 overturned that presupposition,
  twice over: (a) the unconditional registration broke all 94
  pre-existing `high`/`critical` contracts (`check-contract` 0/94;
  the `mcp-tests` CI job red at 231/1), and (b) the backfill is
  structurally disqualified — all 94 contracts are hash-bound
  `artifacts[]` entries in their tasks' evidence bundles, so editing
  them trades the missing-check failure for the tampered-artifact
  failure H-02.2 exists to catch, and `check-contract` offers no
  grandfather path, so each backfilled entry must claim `passes:true`
  with a `producer.sha256` matching the live script — 94 byte-identical
  records attesting nothing, armed against a Pass-7 tripwire that any
  future edit to `check-component-coverage.py` detonates (measured: 79
  pass → 0 pass on a one-line comment; epic-192 is scheduled to edit
  that script). The sanctioned remedy is now **conditional activation**
  (staged human-copy candidate, commit `eb427d60`): `check-contract`'s
  `_pass4_risk_tier` drops `check-component-coverage` — and only that
  id — from the `high`/`critical` tier minimum exactly while
  `sdd/project-context.yaml` is absent, the same state in which the
  Gate itself derives `disabled-legacy` and can assert nothing. The
  predicate is file presence, not a re-derived three-way state:
  `contracts/project-context.schema.json` makes `capability_enforcement`
  required with enum `advisory|required`, so presence is exactly
  equivalent to `derive_state() != disabled-legacy` for every
  schema-conformant config, fail-closed (check still required) for a
  malformed one, and no YAML parser — whose caught exception would
  silently conclude `disabled-legacy` and turn the minimum off forever —
  participates in the decision. Measured against a candidate-patched
  tree: `check-contract` 79/94 (the 15 residual failures are
  pre-existing missing-evidence findings unrelated to this check),
  `tests/gates.tests.sh` 126/0 with the unrepaired live suite,
  `mcp-tests` 232/0; non-vacuity was mutation-proven (stuck-open,
  stuck-shut, and inverted-condition mutants each caught).

## Dependencies

- **Epic A1 (Project Context) — schema shape (hard dependency)**: Epic A1
  owns the `project-context.yaml` schema, including the exact field types
  for `components[].paths.include`, `components[].paths.exclude`, and
  `shared_paths[]` (decision-document v2 §12's example). This feature does
  not redefine that schema, but — unlike an earlier draft that treated
  divergence-reconciliation as a purely tracked follow-up, and unlike a
  later draft that conditioned the fixture on schema arrival ("once Epic
  A1's schema lands") — T-001's own Done state is gated on a
  schema-conformance fixture (AC-011) that is part of T-001's own test
  suite from the start and is written to **FAIL closed, not skip or
  conditionally pass**, whenever Epic A1's canonical schema artifact is
  absent from the repository at the fixed, documented path this fixture
  checks, and to fail whenever the artifact is present but this feature's
  parser's field names/types/version diverge from it. There is no
  schema-presence-gated deferral: the fixture's unconditional FAIL-on-
  absence behavior is what deterministically blocks T-001 from reaching
  Done while Epic A1's schema is unlanded, not merely a documented-but-
  unenforced blocker note. The matching *algorithm* itself (glob semantics,
  NFC/case rules) remains this feature's own design authority and
  ADR-0025 candidate — only the schema *shape* conformance is elevated
  here.
- **Epic A1's canonicalizer** (YAML 1.2 + JCS, Python single implementation
  + thin wrappers, decision-document v2 §18.3/§21 Epic A1) is a hard
  dependency for REQ-005 (`ownership_digest` emission) — there is no
  shape-only substitute for calling a canonicalization utility that does
  not yet exist (INV-002). REQ-005's task is blocked on Epic A1 shipping
  this utility.
- **Epic A1's Provider Bindings schema addition — `adapter_paths`**: Fail-6
  (REQ-004) requires Epic A1 to add an optional `adapter_paths: string[]`
  (glob array) field per binding entry to `sdd/provider-bindings.yaml`'s
  schema (OQ-001, resolved). The Fail-6 adapter_paths trigger rule stated
  above (Fail-condition definitions) and AC-033 are the current normative
  statement of the join rule; investigation.md OQ-001 records only the
  historical decision trail that produced it, not an independently
  restated rule. This feature consumes that field (matched via REQ-001's own glob engine against the
  binding's declared `provider_binding_ids` join key already fixed by
  decision-document v2 §5/§12) — it does not otherwise define or
  redefine the Provider Bindings file schema (Non-goals).
- **Epic A1's `contracts/project-context.template.yaml` — single
  canonical seed inventory (cross-epic dependency)**: Epic A1 owns and
  ships `contracts/project-context.template.yaml`; its `shared_paths`
  section is the **sole canonical source** of the default cross-cutting
  seed list — `specs/**`, `reports/**`, `docs/**`, `.github/**`,
  `tests/fixtures/**`, and `CHANGELOG.md`, each classified
  `cross-cutting` (`docs/**` subsumes the earlier narrower `docs/adr/**`
  entry, so no separate `docs/adr/**` line is needed). This embedding
  instruction has already been issued to Epic A1 by the orchestrator
  separately (assigning cross-epic work is outside this feature's own
  authority); **A3 authors no competing or duplicate seed-list document of
  its own** (Non-goals). This feature's own obligation is limited to
  REQ-007's day-one cross-epic integration fixture (AC-042, AC-044), which
  reads `contracts/project-context.template.yaml` directly (once it
  lands) and verifies (a) its `shared_paths` section's cross-cutting
  entries exactly match the six-entry set above, and (b) a
  `project-context.yaml` shaped like that template does not trip Fail-1 on
  an ordinary day-one `specs/**`/`reports/**` change — while A1's template
  is absent from the repository, this fixture FAILS closed (block), never
  passing via a stand-in (Non-goals still excludes implementing A1's own
  bootstrap flow).
- **Epic A4 (Facet Manifest)** owns the schema for
  `facet-manifest.affected_components`, the field Fail-2 and Fail-4 (REQ-004)
  compare the resolver's output against. This is a genuine forward
  dependency created by the decision document's own epic ordering
  (§19: A1 → A2 → A3 → A4 → A5; INV-003). REQ-004 resolves this not with a
  file-presence-driven degraded mode (rejected, see Problems and REQ-004),
  but by deriving the Gate's *invocation* itself from the
  `workflow.capability_enforcement`/`disabled-legacy` axis (ADR-0016,
  INV-016): no ownership Fail-condition evaluation happens at all while
  the capability pipeline is `disabled-legacy` (the script still runs,
  only to record that true fact, NEW-001), and by the epic sequencing
  above, a project only sets `capability_enforcement` to `advisory` or
  `required` once the pipeline it depends on (including Facet Manifest
  generation, Epic A4/A5) is operational — so the practical window in
  which the Gate is "evaluating but manifest-less" is a misconfiguration
  to fail closed on (a hard error, AC-028), not a steady-state mode to
  design a silent WARN-and-continue path for.
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
  (INV-017). This same staged `check-contract.{sh,ps1,py}` human-copy
  candidate additionally gains a **producer-digest verification pass**
  (INV-018, INV-019): it independently recomputes the sha256 of the
  live, on-disk `check-component-coverage.py` and rejects a `passes:true`
  evidence entry whose recorded `producer.sha256` field does not match —
  no new protected-file family is introduced by this, only an additional
  validation pass inside the edit this feature already stages. The same
  staged edit also carries the 2026-08-11 conditional-activation
  supersession (Problems): the tier-minimum requirement for this one id
  activates only once `sdd/project-context.yaml` exists. This
  closes the gap (Problems; formerly a NOT_RESOLVED verification finding)
  where an unprotected caller could be replaced and paired with a
  fabricated `passes:true` evidence entry pointing at any existing file;
  per the two-tier defense-claim scope this mirrors (ADR-0019
  `docs/adr/0019-approval-sidecar-protection.md:70-77,96-103`; Security
  Boundaries below), this closes tamper-evidence/footgun exposure, not an
  unconditional adversarial-agent-proof reachability guarantee.

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
    landed canonical schema (Dependencies); this conformance fixture is
    part of T-001's own test suite from the start and is written to FAIL
    closed — not skip or conditionally pass — whenever that schema
    artifact is absent from the repository, and to fail whenever it is
    present but diverges from this feature's parser — a hard, not
    follow-up, dependency for this REQ's own Done state, enforced
    deterministically rather than merely documented (AC-011).
  - **Config-read contract on a present-but-malformed file (stated
    2026-08-11 as part of the Gate-side ruling's class sweep,
    REQ-004)**: a `--config` file that exists but cannot be parsed is a
    fail-closed load-time error — non-zero exit with a diagnostic
    naming the parse failure — the same load-time-error class this
    feature already pins for unsupported metacharacters (AC-006), an
    empty `include` list (AC-008), and REQ-002's ill-shaped
    `shared_paths` entry (AC-018). The resolver has no applicability
    derivation and no `disabled-legacy` state, so there is no fallback
    a parse failure could be converted into; this clause states
    explicitly what that load-time-error class already implied, so no
    reader infers a resolver-side analogue of the Gate's file-absence
    fallback. The resolver-only diagnostic subcommand (`--diagnose`,
    REQ-004) is the same script and the same parser and inherits this
    identical contract.

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
    Manifest file happens to exist. Unlike an earlier draft that collapsed
    `advisory` and `required` into one "capability-active" bucket with
    identical blocking behavior — silently promoting `advisory` to
    `required`'s enforcement strength, contrary to ADR-0016's own "governs
    whether capability-specific gates are advisory or required"
    distinction (`docs/adr/0016-workflow-axes-separation.md:44-45`,
    NEW-001 finding, INV-018) — `check-component-coverage` **always runs**
    and **always emits a real, truthful evidence record** (Data Plan); it
    is the record's `state` field and exit code, not whether the script
    ran at all, that vary across the three derived states below. (Scope
    note added 2026-08-11, human-directed ruling: "always" quantifies
    over the three derived states; a `--config` file that exists but
    cannot be parsed derives no state and produces no record — the Gate
    hard-errors first, per the present-but-malformed sub-bullet below.)
    **Superseded (2026-08-11, human-directed)** — this bullet originally
    continued: "This also closes the required-check-set incompatibility
    (NEW-001): a `disabled-legacy` `high`/`critical` task has a genuine,
    non-fabricated `passes:true` evidence entry to satisfy
    `check-contract`'s tier minimum (Dependencies), never a choice
    between 'no evidence exists' and 'a fabricated pass.'" That closure
    held only for tasks gated after the registration landed; for the 94
    pre-existing `high`/`critical` contracts it prescribed backfilling
    minted evidence records, which measurement disqualified (Problems:
    hash-bound bundles, no grandfather path, Pass-7 producer-digest
    tripwire). The required-check-set incompatibility (NEW-001) is now
    closed by **conditional activation** instead: the staged
    `check-contract.{py,ps1}` candidate (`eb427d60`) drops
    `check-component-coverage` from the `high`/`critical` tier minimum
    exactly while `sdd/project-context.yaml` is absent — the same state
    in which the Gate derives `disabled-legacy` and can assert nothing —
    so a `disabled-legacy` task (including every pre-existing contract)
    is not required to carry the entry at all, and the minimum activates
    precisely when the Gate becomes capable of asserting something. The
    Gate's own always-run/always-emit contract below is unchanged: its
    genuine records remain producer-digest-verifiable in every state
    (the Pass-7 verification is not state-gated), and once the project
    context lands, the activated minimum is satisfiable only by such a
    genuine record — never a choice between "no evidence exists" and "a
    fabricated pass."
    - **`disabled-legacy`** (derived state, ADR-0016 §4): the script still
      runs, reads the same `--config`, and determines it is in this
      state — it performs **zero** ownership Fail-condition evaluation
      (no `git diff` collection, no Facet Manifest read, `--facet-manifest`
      accepted but never consulted for existence) and records a
      machine-readable `state: "not-applicable (disabled-legacy)"` in its
      evidence output (Data Plan) as a **true statement about a real
      execution**, not a silent skip or a placeholder pass — exit 0.
      `quality-gate`'s `## Process` step treats this outcome as an
      expected no-op. This mirrors ADR-0016 §4's requirement that the
      entire capability evaluation pipeline sits outside its own domain in
      this state, while still emitting a genuine record `check-contract`'s
      producer-digest pass can validate whenever one is present — under
      the 2026-08-11 supersession (above), the tier minimum itself no
      longer requires this id in this state (NEW-001).
    - **`advisory`**: the Gate **is** invoked, and by construction requires
      a Facet Manifest — `--facet-manifest <path>` is a structurally
      required flag in this state (its own argument-parsing enforces
      presence). If the supplied manifest path is missing or unreadable,
      this is a **hard error** (distinct, non-zero exit code) — never a
      WARN + exit 0. When present and readable, all six Fail conditions
      from decision-document v2 §12 are evaluated and every finding is
      recorded in the evidence output, but the script **always exits 0**
      regardless of any Fail condition triggering — `advisory` means
      evaluated-and-recorded, never blocking (ADR-0016
      `capability_enforcement: advisory`).
    - **`required`**: identical Facet-Manifest-required/hard-error
      behavior and full six-Fail-condition evaluation as `advisory`, but
      the script exits **non-zero iff at least one Fail condition
      triggers** — `required` means evaluated, recorded, AND blocking.
    - **Present-but-malformed config — the Gate itself fails closed
      (added 2026-08-11, human-directed ruling)**: the ADR-0016
      file-absence fallback named above is for **absence only** —
      INV-016 records ADR-0016's own scoping (a file-existence fallback
      used ONLY for the compatibility case where `project-context.yaml`
      itself is absent). When the `--config` path names a file that
      **exists but cannot be parsed**, no state is derived at all:
      `check-component-coverage` itself must exit non-zero with a
      diagnostic naming the parse failure and must emit **no evidence
      record**. No code path may catch the parse exception and convert
      it into `disabled-legacy` (or any other derived state) — the
      same prohibition Problems/AC-035 already state for
      `check-contract`'s file-presence predicate, now stated for the
      Gate's own read of the same file. The reason is identical on
      both sides: a caught parse failure that silently concluded
      `disabled-legacy` would emit a genuine, producer-digest-valid
      `state: "not-applicable (disabled-legacy)"` record (AC-055
      verifies producer identity, never config validity), satisfying
      the activated tier minimum while the config is broken. With the
      Gate crashing recordless and `check-contract` keeping the check
      required (fail-closed predicate, TEST-035c), a `high`/`critical`
      contract fails on the missing required check and the pipeline
      stays red until the config is fixed — the Gate-side half of
      AC-035's end-to-end fail-closed guarantee (TEST-035d). A
      distinct, unchanged condition: a config that **does parse** but
      whose `workflow.capability_enforcement` is absent or not one of
      `advisory`/`required` derives `disabled-legacy` under ADR-0016
      §4's conservative derivation — a statement about successfully
      parsed content (the axis is not validly declared), never a
      converted exception. Such a document is non-conformant to
      `contracts/project-context.schema.json` (which makes
      `capability_enforcement` required with enum `advisory|required`);
      in that state the tier minimum is active (the file exists) and is
      satisfiable by the Gate's genuine `disabled-legacy` record — a
      truthful, visible statement that the capability axis is not
      validly declared, with the misdeclaration observable both in the
      record's own `state` field and to Epic A1's schema surface
      (Dependencies) — not a silent parser downgrade, which is the
      sole failure mode this ruling forbids. This closes the class:
      every component this feature governs that reads
      `sdd/project-context.yaml` now has a stated
      present-but-malformed contract — this Gate (this bullet),
      `check-contract`'s predicate (fail-closed, no parser
      participating; Problems, AC-035, Edge Cases), and the resolver
      with its `--diagnose` subcommand (fail-closed load-time parse
      error, REQ-001); no other component this feature ships reads
      that file.
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
    semantics) matches an EXCLUSIVE-owned changed path triggers Fail-6 —
    the `adapter_paths` glob match against the changed path is the sole
    trigger condition; no additional per-binding "facet" or "revision"
    field is defined by this feature or by Epic A1's Dependencies-scoped
    schema addition (see Design Decisions "Fail-6 scope" in design.md). A
    binding whose declared `adapter_paths` glob does not match any
    EXCLUSIVE-owned changed path does not trigger Fail-6. A binding that
    exists but does not declare `adapter_paths` records Fail-6 as WARN
    "evaluation not possible" (evidence-logged) rather than silently
    passing. When `sdd/provider-bindings.yaml` itself is absent, Fail-6 is
    recorded N/A with a WARN.
  - **Resolver-only diagnostics are not a Gate mode.** The subset of
    checks that need only the resolver's own output (Fail-1/3/5/6-
    conditional) is retained, but repackaged as an independent, non-Gate
    diagnostic command (`resolve-component-paths --diagnose`, or an
    equivalently named standalone entry point decided at task
    decomposition) that a maintainer or CI job may run for early feedback
    at any time, regardless of capability state, whose exit code never
    affects the Implementation Gate and which `quality-gate`'s
    `## Process` never invokes.
  - **Protected required-check-set registration + evidence producer
    binding (reachability, INV-017; evidence tamper-evidence, INV-018,
    INV-019)**: `check-component-coverage` is registered as a required
    contract-check id for `high`/`critical` tier tasks in
    `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (unprotected,
    direct edit) *and* in `check-contract`'s own protected, hardcoded
    tier-minimum set (`check-contract.{sh,ps1,py}`, staged via human-copy
    since `check-contract.*` is already R-10 protected,
    `guard-invariants.json:14-16`). The entry's *requirement* is
    capability-state-gated per the 2026-08-11 supersession (Problems;
    applicability sub-bullet above): it participates in the evaluated
    tier minimum only once `sdd/project-context.yaml` exists. The same
    staged `check-contract.*`
    candidate additionally gains a producer-digest verification pass: a
    `passes:true` `check-component-coverage` evidence entry must be an
    `emit-run-record`-conformant record (Data Plan) whose `check_id`
    matches the registered id and whose `producer.sha256` field equals the
    sha256 `check-contract` independently (re-)computes over the live,
    on-disk `check-component-coverage.py` at verification time — a
    mismatch, or a missing `producer` field, fails the contract. This
    two-part registration means deleting or renaming the
    `quality-gate/SKILL.md` invocation, or substituting an unregistered
    replacement script paired with a fabricated `passes:true` entry
    pointing at any existing file, still fails a `high`/`critical` task's
    Gate — the required-check-set closes the first gap (INV-017), and the
    producer-digest pass closes the second (Problems; formerly a
    NOT_RESOLVED verification finding). Per the two-tier defense-claim
    scope this deliberately mirrors (ADR-0019
    `docs/adr/0019-approval-sidecar-protection.md:70-77,96-103`; Security
    Boundaries): this guarantees **footgun prevention and tamper-evidence**
    (a naive/accidental bypass, or a crude same-file substitution, is
    caught deterministically) — it does **not** claim unconditional
    reachability against an adversarial agent, which instead depends on
    the external boundary (the protected files themselves, an
    HMAC-signed evidence bundle at `high`/`critical` tier per
    `deterministic-check-policy.md`, branch protection/CODEOWNERS, and
    human review).
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

- REQ-005 (`ownership_digest` emission — full ownership-input binding; §16
  Q15, ADR-0021): The resolver emits `ownership_digest` — a digest of the
  **entire** ownership input declared in the project's config: **every**
  component's `paths.include`/`paths.exclude` entries and **every**
  `shared_paths` entry, unconditionally, plus the matcher semantics/
  rule-set version (ADR-0025 candidate) identifier — not a per-resolve-
  scoped subset of entries a given diff happened to reference or match.
  There is no "evaluated but not matched" versus "never evaluated" split:
  per-path classification (EXCLUSIVE vs. OVERLAP vs. UNOWNED, and
  `shared_paths` precedence, REQ-002) is a function of every declared
  component's entries and every `shared_paths` entry simultaneously
  (deciding EXCLUSIVE requires checking every other component's residual
  match too; deciding OVERLAP/UNOWNED likewise), so no proper subset of the
  ownership input can be soundly labeled "unconsumed" by a given resolve —
  a selective, evaluated-subset binding is not a scoping refinement, it is
  unsound. `ownership_digest` is therefore identical for every Feature
  sharing the same ownership config at a given commit, and changes
  whenever **any** component's paths or **any** `shared_paths` entry (or
  the matcher semantics version) changes anywhere in the config —
  including an entry that does not, and never would, match a given
  Feature's own changed-path set. This closes the selective-stale blind
  spot where a previously non-matching pattern's edit (e.g. a component's
  `include` list widening to now cover a path it previously didn't) would
  otherwise leave a stale Feature's digest unchanged because only a
  narrower "matched" or "evaluated" set was bound. Because the digest is
  now a blunt, project-wide "the ownership config changed" signal rather
  than a per-Feature-scoped one, ADR-0021's downstream **semantic-output**
  comparison (not the digest itself) is what keeps staleness selective —
  see AC-040. Canonicalized via Epic A1's YAML-1.2-plus-JCS canonicalizer
  (decision-document v2 §18.3; not reimplemented here, per the task's
  scope-boundary instruction). `ownership_digest` populates the
  `context_binding` block exactly as ADR-0021
  (`docs/adr/0021-context-projection-staleness.md` lines 41-42, 78-88)
  specifies, alongside `resolver.version`/`resolver.rule_set_revision`; it
  is binding/provenance metadata, excluded from ADR-0021's "semantic
  output" comparison (lines 55-68) — a digest-only update, with no change
  to which components are reported affected, never by itself marks a
  Feature stale. A regression/positive-and-negative test matrix (owner
  added, owner removed, a non-match→match transition unrelated to a given
  Feature's diff, a bounded-shared-entry change unrelated to that diff, an
  edit entirely disjoint from that diff proving full-input binding does
  not itself cause blanket staleness, and a matcher-semantics-version
  bump) proves both the digest's own always-changes-on-any-edit behavior
  and ADR-0021's wider semantic-output comparison and
  `context_binding`/`resolver` metadata update behavior, not the digest
  value in isolation.

- REQ-006 (cross-cutting seed-inventory cross-epic validation; §12
  "v2 新設"; single-source-of-truth consolidation): Epic A1's
  `contracts/project-context.template.yaml` is the **sole canonical
  source** of the default cross-cutting `shared_paths` seed list —
  `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`,
  and `CHANGELOG.md`, each classified `cross-cutting` (`docs/**` subsumes
  the narrower `docs/adr/**`, so no separate entry is needed for it). A3
  authors **no** competing or duplicate reference document of its own
  (corrected from an earlier draft that positioned an A3-authored
  `plugins/sdd-quality-loop/references/default-shared-paths.md` as the
  canonical source — that framing is withdrawn; if such a file exists at
  all going forward it is, at most, a non-canonical cross-reference
  pointing at A1's template, never an independent enumeration that could
  drift out of sync with it). `contracts/**` is deliberately **not** on
  this list (Design Decisions) — decision-document v2 §12 itself shows
  `contracts/**` as a **bounded** shared example
  (`components: [desktop-client, sync-api]`), distinct from `docs/**`'s
  own unbounded cross-cutting example; treating `contracts/**` as
  unbounded cross-cutting would silently drop the very
  component-enumeration Fail-4 is meant to enforce for it. This feature's
  own obligation is the cross-epic validation itself: REQ-007's day-one
  integration fixture (AC-042, AC-044) reads
  `contracts/project-context.template.yaml` directly (once it lands) and
  proves both that its `shared_paths` section's cross-cutting entries
  exactly match the six-entry set above and that a Project Context shaped
  like that template does not trip Fail-1 on an ordinary day-one
  `specs/**`/`reports/**` change — while A1's template is absent from the
  repository, this fixture FAILS closed (block), never passing via a
  stand-in (see Non-goals for the narrower scope that remains genuinely
  out of bounds).

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
  comparison key), one fixture per REQ-001 glob clause id, and a day-one
  cross-epic fixture reading Epic A1's
  `contracts/project-context.template.yaml` directly (REQ-006, AC-042,
  AC-044), is created and exercised by new `.sh`/`.ps1` test suite twins
  covering each of the
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

- REQ-009 (dual-runtime parity contract, product-wrapper-direct
  comparison): An independent parity harness feeds the *identical* fixture
  and argv **directly to each product wrapper pair** —
  `resolve-component-paths.sh` vs. `resolve-component-paths.ps1`, and
  `check-component-coverage.sh` vs. `check-component-coverage.ps1` (the
  only two product wrapper pairs this feature ships; the git-diff basis,
  T-002, and `ownership_digest` emission, T-003, are internal stages of a
  single `resolve-component-paths` invocation, not independent wrapper
  pairs of their own, and are exercised through that same wrapper) — and
  asserts, via a defined canonical normalized-stdout-JSON form (design.md:
  parse as JSON, re-serialize with object keys sorted at every nesting
  level, arrays left in original order since order is itself semantically
  meaningful per AC-010's stable sort, no trailing whitespace), byte-for-
  byte identical output, identical exit code, identical WARN/error
  category strings, and identical argument pass-through behavior
  (including an unrecognized or extra argument, and, on the PowerShell
  side, `$LASTEXITCODE`) — a fixture where only the `.ps1` wrapper drops
  an untracked argument, or mishandles `$LASTEXITCODE`, must fail this
  harness even when each wrapper independently passes its own
  same-language test suite (the failure mode this feature's earlier "both
  files exist" proof, and a suite-twin-only comparison, could not catch,
  since neither actually runs the two product-wrapper runtimes
  side-by-side against the identical invocation). The parity harness is
  itself registered in `tests/run-all.sh`/`.ps1` and staged into
  `.github/workflows/test.yml` via human-copy, alongside the suite pairs.

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
  itself, or authoring any seed-list document of A3's own that competes
  with or duplicates Epic A1's `contracts/project-context.template.yaml` —
  that template's `shared_paths` section is the single canonical source of
  the default cross-cutting seed list (Dependencies); A3 defines no list
  of its own. REQ-007's fixture/integration test (AC-042, AC-044) proves
  that canonical inventory is complete and effective once applied — using
  Epic A1's shipped template as its fixture once it lands, or a fixture
  matching that template's documented shape before then (narrower than an
  earlier draft's blanket "no bootstrap proof at all" non-goal — see
  REQ-006).
- Any change to `sdd-hook-guard.*`'s own enforcement logic — this feature
  only adds new entries to protected *data*/*policy* files
  (`guard-invariants.json`, `generate-guard-invariants.py`'s inventory
  tuple, `check-contract`'s tier-minimum set, `risk-gate-matrix.md`) the
  existing guard/gate scripts already read, plus — **amended 2026-08-11
  (human-directed supersession; Problems, REQ-004)** — the
  capability-state activation predicate for the one tier-minimum entry
  this feature itself adds (`_pass4_risk_tier` drops
  `check-component-coverage` from the `high`/`critical` minimum while
  `sdd/project-context.yaml` is absent) and the producer-digest
  verification pass (Dependencies), both carried by the same staged
  `check-contract` human-copy candidate (`eb427d60`). As originally
  written, this bullet scoped the sanctioned `check-contract` change to
  "adds new entries" only; that narrower scope presupposed the
  94-contract backfill that measurement overturned on 2026-08-11
  (Problems). No other check id gains a capability-state axis, no
  general capability-awareness is added to the tier mechanism, and
  `sdd-hook-guard.*`'s enforcement logic remains untouched.

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
- As a maintainer relying on `contracts/project-context.template.yaml`
  (Epic A1's own shipped artifact, and the single canonical source of the
  default cross-cutting seed list), I need A3's day-one cross-epic
  integration test to fail loudly the moment that template's inventory
  ever diverges from the agreed six-entry set, rather than each side
  silently drifting its own copy, so a brand-new Project Context never
  immediately fails every Feature's Gate on routine `specs/**` changes
  (REQ-006, REQ-007, Dependencies).
- As a maintainer relying on ADR-0021's staleness mechanism, I need my
  in-progress Feature to never be spuriously marked stale by an unrelated
  path-ownership edit elsewhere in the monorepo — even though
  `ownership_digest` itself now changes on *every* ownership-input edit
  project-wide, because it binds the entire declared ownership input, not
  a per-Feature-scoped fragment (REQ-005) — and I need a *previously
  non-matching* pattern becoming a match to be provably caught the moment
  it is edited, not only when my Feature's own diff happens to touch it;
  it is ADR-0021's semantic-output comparison, not the digest's scope,
  that keeps my Feature's actual staleness selective.
- As a maintainer whose project has not yet adopted the capability
  pipeline, I need `check-component-coverage` to perform zero ownership
  evaluation and never block or WARN me — while still leaving behind a
  real, truthful `state: "not-applicable (disabled-legacy)"` evidence
  record rather than either a fabricated pass or a permanently-unsatisfiable
  required-check-set entry — so ADR-0016's `disabled-legacy` guarantee
  holds for this Gate's *evaluation* the same way it holds for every other
  capability-driven component, without breaking `check-contract`'s
  required-check-set mechanism for `high`/`critical` tasks (REQ-004,
  NEW-001).

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
  whose pattern matches zero changed paths in a given resolve triggers no
  Fail-4 check for that resolve (Fail-4 requires an actual match) — this
  is a classification-level fact about that one resolve's Fail-condition
  outcome only, and carries no implication for `ownership_digest`'s scope:
  the entry remains part of the full ownership input REQ-005 always binds
  into the digest, matched or not, in this or any other resolve (a
  zero-match outcome is never itself a digest-scope exemption, AC-037).
- AC-010 (REQ-001, NFC collision + raw identity): two distinct raw git
  paths that differ only in Unicode normalization form (one NFD-encoded,
  one NFC-encoded) and therefore normalize to the identical comparison key
  is a fail-closed collision error — the resolver never silently merges,
  drops, or arbitrarily picks one; every output record preserves the
  path's original raw bytes (not the normalized comparison key) for
  identity purposes, and output ordering is a stable sort over raw path
  bytes, deterministic even when a collision is present.
- AC-011 (REQ-001, schema conformance, FAIL-closed on absence): a
  dedicated schema-conformance fixture, part of T-001's own test suite
  from the start, looks for Epic A1's canonical `project-context.yaml`
  schema artifact at a fixed, documented repository path and **FAILS
  (non-zero, red) if that artifact is absent** — never a skip, never a
  conditional pass gated on "once the schema lands." When the artifact is
  present, the same fixture validates this feature's parser against that
  schema's actual field names/types/version for
  `components[].paths.include/exclude` and `shared_paths[]`, and fails on
  any divergence from decision-document v2 §12's shape this feature
  currently builds against. Both failure modes are the same fixture's
  ordinary red state, so T-001 is deterministically blocked from Done
  while Epic A1's schema is unlanded or divergent — not merely documented
  as blocked.
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
  derived state (`disabled-legacy`/`advisory`/`required`) is derived
  solely from `workflow.capability_enforcement`/the ADR-0016 file-absence
  fallback (read from the same `--config` input as REQ-001), never from
  Facet Manifest file presence; a fixture where the manifest file happens
  to be present but `capability_enforcement` derives `disabled-legacy`
  still results in the script recording the `disabled-legacy` state (no
  ownership Fail-condition evaluation, the manifest is never consulted for
  existence or content) rather than evaluating Fail conditions against
  that present manifest, proving file presence is not consulted as a
  selector even though the script itself still runs (AC-027).
- AC-027 (REQ-004, `disabled-legacy` truthful non-evaluation): in the
  `disabled-legacy` derived state, `check-component-coverage` still runs
  to completion and emits a real evidence record (Data Plan) whose
  `state` field reads `"not-applicable (disabled-legacy)"` — no Fail
  condition is evaluated, no WARN is recorded, and the exit code is 0; a
  fixture confirms this record is genuine (not a placeholder, and not
  merely a stdout skip line with no evidence artifact) so `check-contract`'s
  required-check-set (Dependencies) has real, non-fabricated evidence to
  validate; `quality-gate`'s `## Process` treats this outcome as an
  expected no-op.
- AC-028 (REQ-004, manifest-required hard error): in either the
  `advisory` or `required` derived state, a missing or unreadable
  `--facet-manifest` path produces a hard error — a distinct, non-zero
  exit code from an ordinary Fail-condition trigger — never a WARN + exit
  0 degrade.
- AC-029 (REQ-004, resolver-only diagnostics separated): the Fail-1/3/5/6-
  conditional resolver-only checks exist only as an independent, non-Gate
  diagnostic command; `quality-gate`'s `## Process` never invokes it, and
  its exit code never affects the Implementation Gate.
- AC-030 (REQ-004): each of Fail-1 through Fail-6 has at least one
  dedicated fixture that deterministically triggers it when the Gate is
  invoked with a present, readable Facet Manifest, identically in both the
  `advisory` and `required` derived states (evaluation and evidence
  recording do not differ between them — only the exit code does, AC-052/
  AC-053) (Fail-6's fixture includes a `sdd/provider-bindings.yaml` file
  with `adapter_paths` declared).
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
  triggers Fail-6 — the `adapter_paths` glob match is the sole trigger
  condition; a binding whose declared `adapter_paths` glob does not match
  any EXCLUSIVE-owned changed path does not trigger Fail-6. A binding
  lacking `adapter_paths` records Fail-6 as WARN "evaluation not possible"
  (not N/A, not a silent pass).
- AC-034 (REQ-004): with no `sdd/provider-bindings.yaml` present, Fail-6 is
  recorded N/A with a WARN, never silently omitted without a trace.
- AC-035 (REQ-004, reachability registration — two-tier defense scope):
  `check-component-coverage` is registered as a required contract-check id
  for `high`/`critical` tier in `risk-gate-matrix.md` and in
  `check-contract`'s protected hardcoded tier-minimum set, which now also
  verifies the evidence entry's `producer.sha256` against the live script
  (Dependencies, AC-055; under the 2026-08-11 supersession the
  tier-minimum requirement for this id is active only once
  `sdd/project-context.yaml` exists — a plain file-presence predicate
  with no YAML parser participating, **fail-closed for a malformed
  config**: a `sdd/project-context.yaml` that is present but unparseable
  or schema-divergent still activates the tier minimum (check still
  required), so a caught parse failure can never silently conclude
  `disabled-legacy` and turn the minimum off (Problems) — while the
  producer-digest verification runs in every state). The activation
  boundary itself is observable as a three-way fixture — file absent
  (requirement inactive; a contract without the entry passes), file
  present and schema-valid (requirement active; a contract lacking the
  entry fails), file present but malformed (fail-closed; still fails) —
  specified as TEST-035a/TEST-035b/TEST-035c (amendment of 2026-08-11).
  Amended further on 2026-08-11 (human-directed ruling): the fail-closed
  guarantee is end-to-end only because both halves are pinned —
  `check-contract` keeps the check required for a present-but-malformed
  config (TEST-035c), **and** the Gate's own config read hard-fails on
  the same condition (REQ-004's present-but-malformed sub-bullet):
  `check-component-coverage` itself exits non-zero naming the parse
  failure and emits no evidence record, so no genuine record exists for
  the activated minimum to accept and the contract fails on the missing
  required check until the config is fixed (TEST-035d). Without that
  Gate-side half, an implementation that caught its own parse exception
  and reused the file-absence fallback would emit a genuine,
  producer-digest-valid `disabled-legacy` record satisfying this AC's
  activated minimum while the config was broken — AC-055's digest pass
  verifies producer identity, never config validity, and could not
  catch it.
  A fixture that deletes or renames the
  `quality-gate/SKILL.md` invocation, or substitutes an unregistered
  replacement script and pairs it with a same-id `passes:true` evidence
  entry whose `producer.sha256` does not match the real
  `check-component-coverage.py`, still fails a `high`/`critical` task's
  Gate — that reachability fixture pins `sdd/project-context.yaml`
  present and schema-valid, the state in which the required-check-set
  half it exercises is active. This AC's claim is scoped to the same two-tier defense boundary
  `docs/adr/0019-approval-sidecar-protection.md:70-77` already establishes
  for this repository's other protected mechanisms: the hook layer +
  `check-contract`'s deterministic validator guarantee **footgun
  prevention and tamper-evidence** (an accidental or naive same-file-class
  substitution is caught) — they do not, by themselves, guarantee
  unconditional reachability against an adversarial agent, which
  additionally depends on the external boundary (the protected files
  themselves, `high`/`critical`'s HMAC-signed evidence bundle
  (`deterministic-check-policy.md` §"Risk-tiered enforcement"), branch
  protection/CODEOWNERS, and human review).
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
  computed over the canonical form of the **entire** ownership input
  declared in the project's config — **every** component's
  `paths.include`/`paths.exclude` entries and **every** `shared_paths`
  entry, unconditionally — plus the matcher semantics/rule-set version
  identifier, via Epic A1's canonicalizer. Because per-path classification
  (EXCLUSIVE/OVERLAP/UNOWNED, `shared_paths` precedence) is a function of
  every declared entry simultaneously, no proper subset of the ownership
  input can be soundly labeled "unconsumed" by a given resolve — the
  digest binds the complete input every time, identically for every
  Feature sharing the same config, never a selectively-scoped "evaluated"
  subset; if the canonicalizer does not exist in the repository at
  implementation time, the implementing task records this as a documented
  blocker rather than reimplementing canonicalization.
- AC-038 (REQ-005): `ownership_digest` is present in `context_binding`
  alongside `resolver.version`/`resolver.rule_set_revision`, and is
  excluded from ADR-0021's semantic-output comparison — a fixture where
  only `ownership_digest` changes (no resolved-component-set change) does
  not mark the Feature stale.
- AC-039 (REQ-005, non-match stale regression — an instance of AC-037): a
  fixture where a component `include`/`exclude` entry or `shared_paths`
  entry that did not match a given Feature's changed-path set is edited so
  that it now would match — even though the resolver is invoked against
  the exact same changed paths — changes `ownership_digest`, confirming
  AC-037's full-input guarantee is observably true for this specific,
  previously blind-spot transition, not merely asserted.
- AC-040 (REQ-005, selective-stale positive/negative matrix —
  full-input-binding premise): because `ownership_digest` always binds
  the entire ownership input (AC-037) and therefore changes uniformly for
  every Feature sharing a config on any ownership-input edit, this matrix
  fixes what actually stays selective: ADR-0021's downstream
  semantic-output comparison, never the digest's own scope. Each row
  edits the ownership config, confirms `ownership_digest` changes, then
  checks whether *this Feature's* semantic output (resolved facets, gate
  set, effective minimum enforcement, lite eligibility) and
  `context_binding`/`resolver` metadata are updated accordingly: (a) an
  owner is added for a path in this Feature's diff — digest changes,
  semantic output changes, Feature marked stale; (b) an owner is removed
  for a path in this Feature's diff — digest changes, semantic output
  changes, stale; (c) a non-match→match transition for a path **not** in
  this Feature's diff — digest changes (AC-039), semantic output
  unchanged, **not** stale, only `context_binding`/`resolver` metadata
  refreshed; (d) a bounded-`shared_paths`-entry change unrelated to any
  path in this Feature's diff — digest changes, semantic output
  unchanged, not stale; (e) an edit to a component/shared-path entry
  entirely disjoint from this Feature's diff, in a way that also changes
  every *other* Feature's identical digest simultaneously (proving
  full-input binding does not itself cause blanket staleness even though
  the digest itself is now a project-wide signal) — digest changes,
  semantic output unchanged, not stale; (f) a matcher-semantics/rule-set
  version bump alone with no pattern change — digest changes, and
  semantic output changes only in the sub-case where the bump actually
  alters this Feature's classification results (both the
  unchanged-result and changed-result sub-cases are tested).
- AC-041 (REQ-005, suite wiring): `tests/ownership-digest.tests.sh`/`.ps1`
  is registered in `tests/run-all.sh`/`.ps1`, staged into
  `.github/workflows/test.yml` via human-copy, and appears in design.md's
  own Components/suite inventory; a self-test (grep-based) confirms the
  suite is present in all three registration surfaces.
- AC-042 (REQ-006, cross-epic inventory conformance — single source of
  truth): a cross-epic fixture reads Epic A1's shipped
  `contracts/project-context.template.yaml` directly and asserts its
  `shared_paths` section's cross-cutting entries are **exactly**
  `specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`,
  and `CHANGELOG.md` — no more, no fewer, no differently classified — and
  that `contracts/**` does **not** appear among them (Design Decisions —
  it remains a bounded shared example, REQ-006, REQ-007); a missing entry,
  an unexpected extra entry, or a wrong classification each fail this
  fixture, since A1's template is the sole canonical source and A3 defines
  no competing list of its own; while A1's template is absent from the
  repository, this fixture FAILS closed (non-zero, red, block) — never a
  skip and never a pass via a stand-in — mirroring the same FAIL-closed
  discipline AC-011 established for schema conformance.
- AC-043 (REQ-006): a fixture diff confined to the six-entry set above,
  with zero components declared to own them, never triggers Fail-1.
- AC-044 (REQ-006, day-one cross-epic integration proof): a fixture/
  integration test builds a `project-context.yaml` shaped exactly like
  Epic A1's shipped `contracts/project-context.template.yaml`, read
  directly once it lands, and proves an ordinary day-one
  `specs/**`/`reports/**` change against it does not trip Fail-1
  immediately after the Gate is introduced — the canonical inventory's
  effectiveness is proven, not only documented, and is proven against A1's
  own artifact, not a copy A3 maintains independently; while that artifact
  is absent from the repository, this test FAILS closed (block), never
  passing via a stand-in.
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
- AC-050 (REQ-009, dual-runtime parity harness — product wrapper direct
  comparison): an independent harness feeds the identical fixture and argv
  **directly to each product wrapper pair** —
  `resolve-component-paths.sh` vs. `resolve-component-paths.ps1`, and
  `check-component-coverage.sh` vs. `check-component-coverage.ps1` (the
  only two product wrapper pairs this feature ships; the git-diff basis,
  T-002, and `ownership_digest` emission, T-003, are internal stages of a
  single `resolve-component-paths` invocation, not separate wrapper
  pairs) — and asserts, using the canonical normalized-stdout-JSON form
  (design.md), byte-for-byte identical output, identical exit code,
  identical WARN/error category strings, and identical argument
  pass-through (including an unrecognized or extra argument, and, on the
  PowerShell side, `$LASTEXITCODE`) between each wrapper's two runtimes
  directly — never a comparison between each test suite's own separately-
  authored `.sh`/`.ps1` twin processes. A fixture where the `.ps1` wrapper
  alone drops an untracked argument, or mishandles `$LASTEXITCODE`, fails
  this harness even though both wrapper runtimes independently pass their
  own same-language suite (the failure mode neither the original "both
  files exist" proof, nor a suite-twin-only comparison, could catch, since
  neither actually runs the product wrapper's two runtimes side-by-side
  against the identical invocation).
- AC-051 (REQ-009, parity harness registration): the parity harness is
  registered in `tests/run-all.sh`/`.ps1` and staged into
  `.github/workflows/test.yml` via human-copy, alongside the suite pairs.
- AC-052 (REQ-004, `advisory` non-blocking): in the `advisory` derived
  state, a fixture where at least one Fail condition triggers still exits
  0 — the triggered condition is recorded in the evidence output (Data
  Plan), never silently dropped, but `advisory` never blocks the
  Implementation Gate.
- AC-053 (REQ-004, `required` blocking): in the `required` derived state,
  a fixture where at least one Fail condition triggers exits non-zero,
  blocking the Implementation Gate; a fixture where none trigger exits 0.
- AC-054 (REQ-004, evidence producer binding + emit-run-record
  conformance): every `check-component-coverage` evidence record —
  regardless of derived state (`disabled-legacy`/`advisory`/`required`) —
  is an `emit-run-record`-conformant record (Data Plan) carrying a
  `schema: "check-component-coverage-verdict/v1"` field, a `check_id`
  matching the id registered in `check-contract`'s required-check-set, and
  a `producer.sha256` field computed over the actual, currently-invoked
  `check-component-coverage.py`; a fixture with a mismatched or missing
  `producer.sha256` is rejected by the suite's own self-check.
- AC-055 (REQ-004, `check-contract` producer-digest verification): the
  staged `check-contract.{sh,ps1,py}` human-copy candidate independently
  recomputes `check-component-coverage.py`'s live sha256 at verification
  time and fails a `passes:true` evidence entry whose recorded
  `producer.sha256` does not match; a fixture with a substituted script
  (different sha256) paired with a `passes:true`/matching-id evidence
  entry pointing at a stale or unrelated evidence file fails this check.

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
- **ownership fragment / ownership input**: the *entire* declared
  ownership input — every component's `paths.include`/`paths.exclude`
  entries and every `shared_paths` entry in the project's config — plus
  the matcher semantics/rule-set version, used to compute
  `ownership_digest` (ADR-0021); not a per-resolve-scoped subset — the
  same complete input is bound regardless of which paths a given resolve's
  diff actually touches (REQ-005).
- **`disabled-legacy`** (derived state, ADR-0016): the ADR-0016 derived
  internal state in which `check-component-coverage` still runs and emits
  a real evidence record, but performs zero ownership Fail-condition
  evaluation and records `state: "not-applicable (disabled-legacy)"`;
  exit 0.
- **`advisory`** (derived state): `check-component-coverage` is invoked,
  requires a Facet Manifest (missing/unreadable is a hard error), fully
  evaluates and records all six Fail conditions, but always exits 0 —
  evaluated and recorded, never blocking.
- **`required`** (derived state): identical to `advisory` except the exit
  code is non-zero iff at least one Fail condition triggers — evaluated,
  recorded, and blocking.
- **resolver-only diagnostics**: the independent, non-Gate command
  exposing Fail-1/3/5/6-conditional checks without a Facet Manifest input
  — never invoked by `quality-gate` and never affecting the Implementation
  Gate's exit code.

## Roles and Permissions

- **Implementing agent**: authors `resolve-component-paths.{py,sh,ps1}`,
  `check-component-coverage.{py,sh,ps1}`, the resolver-only diagnostic
  entry point, their test suites and fixtures (including the parity
  harness and the day-one cross-epic fixture reading Epic A1's
  `contracts/project-context.template.yaml`, REQ-006, REQ-007), the new
  ADR, directly edits `risk-gate-matrix.md` (unprotected), and stages
  every protected-file candidate — `guard-invariants.json`,
  `generate-guard-invariants.py`, the four `generated/*` siblings,
  `check-contract.{sh,ps1,py}`, and `.github/workflows/test.yml` — under
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
3. The script emits `ownership_digest` for the *entire* declared ownership
   input (every component's paths and every `shared_paths` entry,
   unconditionally, not only those the current diff touches), plus its own
   computed `affected_components` list.
4. `check-component-coverage` (stage: implementation) always runs and
   reads `workflow.capability_enforcement`/`disabled-legacy` from the same
   config to derive one of three states: `disabled-legacy` (zero
   evaluation, a real `state: "not-applicable (disabled-legacy)"` evidence
   record, exit 0); `advisory` (requires a Facet Manifest, missing/
   unreadable is a hard error, evaluates and records all six Fail
   conditions, always exits 0); or `required` (identical evaluation, but
   exits non-zero iff a Fail condition triggers). Every evidence record it
   emits, in any state, carries an `emit-run-record`-conformant
   `producer.sha256` binding to the script that produced it. It is both
   documented in `quality-gate`'s `## Process` (direct edit) and
   registered in `check-contract`'s protected required-check-set (which
   also verifies the producer-digest binding), so deleting the SKILL.md
   invocation, or substituting an unregistered script, does not bypass it.
   **Superseded in part (2026-08-11, human-directed)** — the closing
   clause above ("so deleting the SKILL.md invocation, or substituting an
   unregistered script, does not bypass it") holds only while
   `sdd/project-context.yaml` exists. Under the same ruling's conditional
   activation (Problems; REQ-004), the tier-minimum membership for this
   id is inactive while that file is absent — the `disabled-legacy`
   state, and this repository's state as of this amendment — so in that
   state `check-contract` requires no `check-component-coverage` evidence
   entry, and an unprotected SKILL.md edit that deletes the invocation is
   NOT caught by this mechanism. What such a bypass forfeits in that
   state is only the truthful `state: "not-applicable (disabled-legacy)"`
   record — no ownership Fail condition was being evaluated to begin
   with — and what still detects the edit is only the external boundary
   (branch protection/CODEOWNERS and human review of the unprotected
   SKILL.md). The producer-digest verification, which runs in every
   state, validates any evidence entry that is present but cannot force
   one to exist. The does-not-bypass guarantee re-arms exactly when
   `sdd/project-context.yaml` lands — fail-closed for a malformed file
   (AC-035; Edge Cases) — the same moment the Gate first becomes capable
   of asserting anything (Security Boundaries). (Extended 2026-08-11,
   same-day human-directed ruling) Within step 4 itself: if the
   `--config` file exists but cannot be parsed, the Gate derives no
   state — it exits non-zero naming the parse failure and emits no
   evidence record (REQ-004's present-but-malformed sub-bullet), and
   the activated tier minimum then fails the contract on the missing
   required check (AC-035, TEST-035d); the workflow stays red until the
   config is fixed, never re-routed through the file-absence
   `disabled-legacy` path.
5. In the `required` state, any Fail condition, or a manifest-required
   hard error (in `advisory` or `required`), blocks the Implementation
   Gate; a human resolves the underlying config or Facet Manifest and
   re-runs. In `advisory`, a Fail condition is recorded but never blocks.
6. Epic A1's `contracts/project-context.template.yaml` is the sole
   canonical source of the REQ-006 default cross-cutting seed list
   (`specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`,
   `CHANGELOG.md`), embedded directly into a new `project-context.yaml`
   (Dependencies, a cross-epic instruction already assigned to Epic A1 by
   the orchestrator; A3 authors no competing list); this feature's own
   cross-epic fixture/integration test (REQ-007, AC-042, AC-044) reads
   that template directly and proves both its inventory matches exactly
   and that a config shaped like it does not trip Fail-1 on a day-one
   adopter's ordinary change, before steps 1-5 run.
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
  still triggers Fail-1 in the `required` derived state (and is recorded,
  non-blocking, in `advisory`) as it would for any other UNOWNED path.
- An empty `changed paths` set (no diff at all between baseline and
  worktree, including untracked) — the Gate passes vacuously; this is
  distinct from, and must not be confused with, a fail-closed
  merge-base-unattainable diagnostic (AC-019), which is an error, not an
  empty result.
- A component with an empty `include` list (a config error, not a runtime
  Fail condition) — flagged at config-load time, not conflated with
  UNOWNED path detection.
- A `shared_paths` entry whose pattern matches zero changed paths in a
  given diff — triggers no Fail-4 check for that resolve (Fail-4 requires
  an actual match); this is a classification-level fact only and is
  independent of `ownership_digest`'s scope, which always binds this entry
  as part of the full ownership input regardless of match outcome
  (REQ-005).
- A Facet Manifest file happens to exist on disk while
  `capability_enforcement` derives `disabled-legacy` — the script still
  runs and records `state: "not-applicable (disabled-legacy)"`, and the
  manifest is never consulted for existence or content; file presence
  never overrides the derived state (AC-026, AC-027).
- A `sdd/provider-bindings.yaml` binding exists for a component but does
  not declare `adapter_paths` — Fail-6 records WARN "evaluation not
  possible" for that binding, distinct from the file-absent N/A case
  (AC-033, AC-034).
- `capability_enforcement` is `advisory` and at least one Fail condition
  triggers — the Gate still exits 0 (`advisory` never blocks), but the
  triggered condition is recorded in the evidence output, not silently
  dropped, so a human reviewing the report still sees it (REQ-004,
  AC-052).
- (Added 2026-08-11 with the conditional-activation supersession,
  Problems) `sdd/project-context.yaml` transitions from absent to
  present — the activation boundary of `check-contract`'s tier-minimum
  membership for `check-component-coverage` (REQ-004, AC-035). The
  behavior is three-way, exercised by TEST-035a/b/c: while the file is
  absent, the tier minimum omits this id, and a `high`/`critical`
  contract without the entry passes `check-contract` (the state of every
  pre-existing contract, and of this repository as of this amendment);
  once the file exists and is schema-valid, the membership is active,
  and an otherwise-identical contract lacking the entry fails; a file
  that is present but malformed (unparseable, or schema-divergent) is
  fail-closed — the check is still required — because the predicate is
  plain file presence and no YAML parser participates in the decision,
  so a caught parse exception can never silently conclude
  `disabled-legacy` and disarm the minimum (Problems). The transition
  needs no migration step: activation is evaluated per `check-contract`
  run, so the first run after the file lands simply evaluates the
  minimum with the id included. (Extended 2026-08-11, same-day
  human-directed ruling) The present-but-malformed row of this boundary
  is two-sided: `check-contract` keeps the check required (fail-closed,
  above, TEST-035c), and the Gate itself — reading the same file as its
  `--config` — exits non-zero with a diagnostic naming the parse
  failure and emits no evidence record (REQ-004's present-but-malformed
  sub-bullet, TEST-035d); the ADR-0016 file-absence fallback never
  applies to a file that is present, so the missing required check
  keeps the pipeline red until the config is fixed.

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
  **Superseded in part (2026-08-11, human-directed)** — the preceding
  sentence overclaims for one state, and this security-guarantee section
  must not overclaim. Under the sanctioned conditional activation
  (Problems; REQ-004; Dependencies), the required-check-set membership
  for this id is evaluated only while `sdd/project-context.yaml` exists.
  While that file is absent — the `disabled-legacy` state, and this
  repository's state as of this amendment — the tier minimum does not
  include the id, so this boundary does NOT prevent an unprotected
  `quality-gate/SKILL.md` edit from bypassing invocation. In that state,
  what a bypass forfeits is only the truthful
  `state: "not-applicable (disabled-legacy)"` record (the Gate performs
  zero ownership evaluation there, so no enforcement is lost); the
  mechanisms that remain are the script-content protection above
  (INV-006), the producer-digest pass (next bullet — it validates any
  evidence entry that is present but cannot force one to exist), and
  the external boundary (branch protection/CODEOWNERS and human review
  of the unprotected SKILL.md), which in `disabled-legacy` is the only
  detection for such an edit. The invocation-reachability boundary this
  bullet originally described becomes real at the moment
  `sdd/project-context.yaml` lands, fail-closed for a malformed file
  (AC-035; Edge Cases): from then on, a `high`/`critical` contract
  lacking the entry fails `check-contract` regardless of any SKILL.md
  edit.
- The required-check-set registration (previous bullet) is strengthened by
  a producer-digest binding (Dependencies; NEW-001, formerly a
  NOT_RESOLVED verification finding): `check-contract` independently
  recomputes `check-component-coverage.py`'s live sha256 and rejects a
  `passes:true` evidence entry whose recorded `producer.sha256` does not
  match, closing the gap where an unprotected caller could be replaced and
  paired with a same-id, fabricated `passes:true` evidence entry. Per the
  two-tier defense-claim scope this mirrors (ADR-0019), this guarantees
  footgun prevention and tamper-evidence, not unconditional
  adversarial-agent reachability — that additionally depends on the
  protected files, the `high`/`critical` HMAC-signed evidence bundle,
  branch protection/CODEOWNERS, and human review as the external boundary.
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
  because there is no degrade path left to force into. Nor can an agent
  force a permissive outcome by setting `capability_enforcement:
  disabled-legacy`: doing so still requires an honest, evidenced
  `state: "not-applicable (disabled-legacy)"` record (Field Definitions),
  and misrepresenting the project's actual capability adoption in
  `project-context.yaml` to obtain that state is a Project-Context
  approval/policy-weakening concern (ADR-0019), not a gap in this
  feature's own Gate logic. **(Extended 2026-08-11, human-directed
  ruling)** The no-degrade guarantee explicitly covers the
  parse-failure surface: a present-but-unparseable
  `project-context.yaml` is a hard, recordless, non-zero exit of the
  Gate itself (REQ-004's present-but-malformed sub-bullet) — never a
  caught exception converted into the file-absence `disabled-legacy`
  fallback, which ADR-0016 reserves for genuine absence (INV-016) — so
  a permissive `disabled-legacy` outcome cannot be obtained by
  corrupting the config rather than deleting it: deletion deactivates
  the tier minimum visibly (Edge Cases), while corruption leaves the
  minimum armed with no record able to satisfy it (AC-035,
  TEST-035d).

## Assumptions

- Decision-document v2 §12's `components[].paths`/`shared_paths` example
  shape is stable enough to build fixtures against now, ahead of Epic A1
  landing its own schema file (Dependencies, OQ-002) — subject to the
  schema-conformance fixture (AC-011), which fails closed (not skips)
  until that schema artifact actually lands and matches.
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
- Epic A1 ships `contracts/project-context.template.yaml` at that fixed
  path with a `shared_paths` section shaped per decision-document v2 §12
  (Dependencies, REQ-006) — while it is absent, REQ-007's day-one fixture
  (AC-042, AC-044) FAILS closed (block), never passing via a stand-in;
  once it lands, the same fixture reads the real artifact directly and
  validates the full inventory against it, under the same FAIL-closed
  discipline AC-011 established for the schema-conformance fixture (a
  missing artifact or a diverging inventory is this fixture's ordinary red
  state, never a skip).
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
  (AC-011), which is written to FAIL deterministically — not skip or
  conditionally pass — while Epic A1's schema is unlanded or divergent, so
  T-001 cannot reach Done in that window without relying on a
  documented-but-unenforced blocker note.

OQ-001 (Fail-6 exact matching rule) is resolved — see the Fail-6
adapter_paths trigger rule in Fail-condition definitions and AC-033 above
for the current normative statement; Dependencies and investigation.md
OQ-001 record the historical decision trail, not an independently
restated rule.

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
  it is instead resolved by gating the Gate's own ownership *evaluation*
  on the derived `advisory`/`required` state (ADR-0016) — the residual
  risk is a project that sets `capability_enforcement` to `advisory` or
  `required` before Epic A4/A5's artifacts genuinely exist, which this
  design treats as an intentional, visible hard error (Assumptions), not a
  silent gap.
- Registering a new protected-gate-suffix entry, and a new protected
  required-check-set entry (REQ-004), via human-copy introduces a window
  between an agent staging the candidates and a human applying them,
  during which `check-component-coverage.*` is NOT yet protected or
  reachability-registered — mitigated by the same window every prior
  protected-file addition in this repository has already accepted
  (INV-006, INV-007, INV-015, INV-017); no new risk class is introduced.
- Binding `ownership_digest` to the *entire* ownership input (REQ-005)
  rather than a selectively-evaluated subset means the digest now changes
  identically for **every** Feature sharing a config on **any**
  ownership-input edit anywhere — a strictly larger blast radius than even
  the earlier "bind every evaluated entry" draft — mitigated by ADR-0021's
  own selective-stale design being the sole source of selectivity from
  this point on (only a Feature whose *semantic output* actually changes
  becomes stale; a digest-only update never does, AC-038/AC-040), so this
  is a correctness fix that trades a coarser, uniform re-resolve trigger
  for a sound digest scope, not a new class of spurious-staleness problem.
- Making `check-component-coverage` always run and always emit evidence
  (REQ-004, NEW-001) — instead of literally skipping invocation in
  `disabled-legacy` — means the script's own runtime cost is paid even
  when its ownership evaluation is a no-op; mitigated by the
  `disabled-legacy` path being deliberately cheap (config-read + a fixed
  evidence record, no `git diff` collection, no Facet Manifest read), so
  this is a bounded, intentional trade for truthful, producer-digest-
  verifiable evidence in every state, not an unbounded cost (the
  required-check-set incompatibility itself is closed by the 2026-08-11
  conditional-activation supersession — Problems, REQ-004).
- Consolidating the default cross-cutting seed inventory onto a single
  canonical source, Epic A1's `contracts/project-context.template.yaml`
  (REQ-006), couples REQ-007's day-one fixture to an artifact this feature
  does not own and that does not exist in the repository yet (INV-002) —
  mitigated the same way AC-011's schema-conformance fixture already
  handles this class of risk: the fixture is written to FAIL closed
  (block, never skip, never a stand-in) while A1's template is absent, and
  against the real artifact once it lands, so a divergence between A1's
  shipped inventory and the six-entry set this spec fixes is always a
  visible, deterministic test failure, never a silent, independently-
  drifting A3 copy.
