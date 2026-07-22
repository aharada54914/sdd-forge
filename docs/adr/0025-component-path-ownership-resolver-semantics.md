# ADR 0025: Component Path Ownership Resolver Semantics

Status: Accepted

Date: 2026-07-23

## Context

Epic A3 (Component Path Ownership, Issue #191, tracked under Epic #187
AI-DLC Foundation) introduces the Reverse Coverage Gate: a deterministic
classifier that, given a repository's declared `components[].paths`/
`shared_paths` configuration (Epic A1's `project-context.yaml` schema,
consumed here, not redefined) and a set of changed paths, decides which
component(s) own each path. `check-component-coverage` (T-004) later turns
an under-reported ownership claim into a blocking Implementation Gate
outcome — but that Gate is only as trustworthy as the classification
beneath it. This ADR records the matching algorithm's semantics, precedence
rules, and Fail-condition definitions T-001 (`resolve-component-paths`)
implements, so a later change to the matcher is reviewed against a written
contract rather than against T-001's source code alone.

Three prior decisions this ADR extends or mirrors:

- `docs/adr/0020-conditional-predicate-dsl.md` establishes this
  repository's restricted-DSL philosophy (a small, explicitly-enumerated
  grammar over an unrestricted/regex/dynamic-code one) for a different
  fragment (predicate conditions). This ADR's glob subset applies the same
  philosophy to path patterns.
- `docs/adr/0021-context-projection-staleness.md` defines the
  `context_binding` shape (`ownership_digest`, `resolver.version`,
  `resolver.rule_set_revision`) this resolver's output populates (T-003);
  this ADR does not restate that shape, only the matching semantics that
  produce the `ownership_input` T-003 binds.
- `specs/epic-136-phase2-gates/` and `specs/epic-159-pillar-c/` establish
  this repository's human-copy staging convention for protected-file
  edits, which this feature's Global Constraints follow for
  `.github/workflows/test.yml` and (T-004) the guard-invariants/
  check-contract bundles.

## Decision

### Glob semantics (REQ-001)

1. **`**` matches zero or more whole path segments**, including crossing
   `/` boundaries and including the **zero-segment** case: `a/**/b`
   matches the literal path `a/b` as well as `a/x/b`, `a/x/y/b`, etc.
2. **A bare `*` matches only within a single path segment** and never
   crosses `/`: `src/*.ts` matches `src/file.ts` but not `src/sub/file.ts`.
3. **`?`, `[...]`, and every other glob metacharacter — and regex, and
   dynamic code — are unsupported.** A pattern string containing one is
   rejected as a fail-closed configuration error at load time (mirroring
   ADR-0020's restricted-DSL philosophy). The implementation's concrete
   rejection set is `?[]{}()!+@^$|~`; `*` and `/` are the only two
   metacharacters this grammar defines.
4. **Normalization is matching-only.** Every pattern string and every
   diff-reported path string is normalized to Unicode NFC, and a
   backslash in a pattern is normalized to forward slash, before matching
   — but the resolver separately preserves each path's original, exact
   raw bytes (as `git` reported them) for identity, output, and sort
   purposes. Two distinct raw paths that normalize to the identical
   comparison key are a fail-closed **collision error** — the resolver
   never silently merges, drops, or arbitrarily picks one.
5. **Matching is always byte-wise case-sensitive**, independent of the
   host filesystem's own case sensitivity, because the resolver only ever
   compares strings returned by `git` plumbing commands — it never lists
   a filesystem directory itself.
6. **Output ordering is a stable sort over raw path bytes** (not the NFC
   comparison key), deterministic even when an NFC collision is present
   in the input (though such an input is itself rejected — the ordering
   guarantee is over the surviving inputs of an otherwise-valid resolve).

### Classification precedence (REQ-002)

For each changed path:

1. **`shared_paths` is checked first.** A match there exempts the path
   from component-exclusivity classification entirely, regardless of how
   many (including zero) components' `include` patterns also match. A
   `shared_paths` entry is one of two mutually exclusive shapes — bounded
   (`components: [...]`) or unbounded (`classification: cross-cutting`) —
   and a config carrying both or neither on the same entry is a
   fail-closed configuration error, distinct from the six Gate Fail
   conditions T-004 defines.
2. **Otherwise, per component:** compute `(include patterns matched) MINUS
   (exclude patterns matched)`.
   - Exactly one component's residual match → **EXCLUSIVE**.
   - Zero components' residual match → **UNOWNED** (Fail-1).
   - Two or more components' residual match → **OVERLAP** (Fail-3).
3. **The exclude/include invariant (Fail-5)**: a path inside component
   C's own `exclude` is never attributed to C, even if it is also nested
   inside one of C's `include` patterns. Where this invariant is the
   *reason* a path is UNOWNED — every component whose `include` would
   otherwise have matched it excluded it — the resolver's per-path output
   record carries an explicit `EXCLUDED_MATCH` evidence tag (the excluding
   component id(s) + matched exclude pattern(s)), distinguishable from an
   ordinary UNOWNED record where no `include` pattern ever matched at all.
   This evidence tag is the concrete, reachable trigger Fail-5 uses at the
   Gate level (T-004's REQ-004), not merely an inference from set
   arithmetic.

### Applicability-derivation decision (shared with T-004)

Whether the Reverse Coverage Gate blocks is derived from
`workflow.capability_enforcement` (ADR-0016), never from Facet Manifest
file presence — this resolver itself performs no applicability
derivation (that is `check-component-coverage`'s own concern, T-004); it
only records here that the classification this ADR defines is identical
regardless of the Gate's eventual `disabled-legacy`/`advisory`/`required`
state, so a classification bug cannot be masked by a particular
enforcement mode.

### Reachability-registration decision

Suffix-protecting `check-component-coverage`'s own content
(`guard-invariants.json`, T-004) does not, by itself, stop an agent from
deleting or renaming the unprotected `quality-gate/SKILL.md` line that
invokes it. `check-contract`'s protected required-check-set additionally
gains `check-component-coverage` at the `high`/`critical` tier (T-004),
independently of SKILL.md's own text — this closes the reachability gap,
scoped as footgun/tamper-evidence prevention per the two-tier defense
`docs/adr/0019-approval-sidecar-protection.md:70-77,96-103` already
establishes, not an unconditional adversarial-agent-proof guarantee.

## Consequences

- A config author must quote a glob pattern beginning with `*` in
  contexts where this repository's restricted YAML-subset config parser
  would otherwise misread the leading sigil (this is a parser
  implementation detail of T-001's own config loader, not a schema rule
  Epic A1 must itself enforce).
- Any future change to the matching algorithm (new metacharacter support,
  a different `**` semantics) is a change to this ADR, not a silent
  code-only change — `check-component-coverage`'s Fail conditions and the
  `ownership_digest`'s full-input binding (ADR-0021) both depend on this
  contract staying stable and documented.
- The schema-conformance fixture (AC-011) that validates T-001's parser
  against Epic A1's landed `contracts/project-context.template.yaml` is
  intentionally, permanently red in this repository until that artifact
  lands — this is a designed, documented external dependency, not a
  defect in this ADR's algorithm or its test suite (see
  `specs/epic-191-a3-path-ownership/tasks.md` T-001 Blockers, and
  `reports/implementation/epic-191-a3-path-ownership/T-001.md`).

## References

- `specs/epic-191-a3-path-ownership/requirements.md` REQ-001, REQ-002
- `specs/epic-191-a3-path-ownership/design.md` Architecture, API/Contract
  Plan, Test Strategy
- `docs/adr/0020-conditional-predicate-dsl.md`
- `docs/adr/0021-context-projection-staleness.md`
- `docs/adr/0019-approval-sidecar-protection.md`
- `plugins/sdd-quality-loop/scripts/resolve-component-paths.py`/`.ps1`/`.sh`
- `tests/component-path-resolver.tests.sh`/`.ps1`
