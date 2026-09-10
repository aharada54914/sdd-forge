# A9 scoped characteristics: consumer decision required

Status: proposed design, NOT an approved specification or implementation.
Date: 2026-09-09 JST
Inspected tree: /Users/jrmag/.local/share/sdd-forge-a9-ci-20260908
Base: 135b147926689bd3adc8c834932a9b82b9f5a607 plus existing document/registry edits.
Historical review outputs, Draft tasks, runtime code and live Context are unchanged.

## Newly established boundary

The remaining problem is not only the missing two characteristic keys.
`contracts/capability-registry.schema.json:140` restricts predicate scope to
`affected_component`; `evaluate-predicate.py:158-162` rejects other scopes and
unlisted fields. In `resolve-component-paths.py:587-590`, a cross-cutting path
has no owning component. Lines 653 and 676 derive/export affected components
only from exclusive and bounded-shared owners. Therefore, by source inspection,
a release-only change classified as cross-cutting has no component on which an
affected-component predicate can evaluate a release override. This is a derived
consequence of the inspected code, NOT a new runtime reproduction.

Issue #193 was fetched directly and remains OPEN. Its input contract expressly
requires A3-derived affected components and forbids introducing self-reported
Change Characteristics. A solution must derive additional views from approved
Context and A3 records, not accept an agent-supplied security label.

Earlier source findings remain relevant: Project Context has seven boolean
characteristics and rejects additional component characteristic keys
(`contracts/project-context.schema.json:40-52`); predicate field names are
closed (`contracts/capability-registry.schema.json:145-148`, evaluator:58-68).
The restricted ownership parser's scalar/schema behavior is described at
`resolve-component-paths.py:703-730`; typed override validation must not treat
quoted strings or the number 0 as boolean false.

Recheck these shared contracts against the actual integration base before
specification/design review or implementation. Line references belong to the
base named above, not an assertion about every open branch.

## Two materially different choices

1. **Recommended: scope-aware runtime integration.** Add a precisely bounded
   path-scope characteristic view and its predicate/evidence contracts. It can
   drive Pack decisions for both an MCP sub-service and a cross-cutting release
   path. This requires a coordinated A1/A2/A3/A5/A9 contract amendment and formal
   reviews, not an A9 YAML-only change.
2. **Classification evidence only.** A dedicated A9 validator consumes the two
   overrides for AC-007/030 evidence without adding Pack predicate semantics.
   Simpler, but explicitly does not make these characteristics affect Pack
   selection or conditional facets. Do not describe it as equivalent to option 1.

Do not choose between these by whichever passes existing tests more easily.
The prior approval of an override mechanism and nine components does not settle
this cross-epic runtime behavior. Option 1 below is a proposal for approval.

## Proposed option 1 contract

- Preserve all nine approved component IDs, directory ownership, seven growing
  shared-directory rules and separate fixed root rules. Never invent a release
  component, attach cross-cutting paths to all components, or widen ownership.
- Use exactly `credential_bearing` and `release_write` as the new characteristic
  vocabulary. An opted-in scope declares an explicit boolean baseline. Missing
  is unknown, not false. Legacy Context without the extension retains old
  behavior; an old consumer must reject an unsupported extension rather than
  silently discard a policy-significant override. Specify the version/capability
  handshake in the amendment; do not claim old strict schemas accept new keys.
- Overrides attach either to an existing component ID or to an exact existing
  cross-cutting rule. Each has a canonical repository-relative path selector,
  one characteristic, a real boolean value, and nonempty rationale. File and
  directory-prefix selectors are distinct, case-sensitive and boundary-aware.
  No arbitrary glob language, absolute path, traversal or symlink-based scope.
- Phase 1 contains exactly two overrides: the CI-MCP subtree's credential
  characteristic and the release workflow's write characteristic. Explicitly
  pin the release workflow path in the amended spec after tracked-tree review;
  do not label all of `.github/**` as release-write.
- Validate each selected path against actual A3 ownership. Reject unknown
  owners/rules/fields, ambiguous matching rules, out-of-scope paths, no-op values,
  duplicate or overlapping overrides for the same characteristic, and malformed
  booleans before predicate evaluation. Neither true nor false may be coerced.
- Produce deterministic per-path effective properties from approved Context,
  verified A3 records and their bound revisions. No caller-supplied effective
  characteristics are admitted. Preserve deleted-path classification using the
  governing A3 change-set contract; never silently drop deletions.
- Introduce an explicitly versioned `affected_path` predicate scope for these
  two fields; leave existing `affected_component` behavior unchanged. One
  expression uses one scope. Reject mixed-scope expressions at construction
  time; never merge values from different files to satisfy an `all` expression.
  Evaluate a path-scope expression separately for each derived path; selection
  is existential over complete per-path expressions, with all path evidence
  retained and deterministic capability/facet deduplication.
- Missing/null/type mismatch remains fail-closed; preserve the existing `not`
  WARN and `exists` semantics. Malformed override input is a construction error,
  not an ordinary non-match. Release-only cross-cutting input must be evaluated
  despite an empty affected-component list, without changing that list.
- Bind the raw approved Context hash, ownership digest, change-set revision,
  override contract version, selector, baseline, override, effective value and
  per-path predicate outcome into resolver evidence. Carry its digest into the
  dependent Manifest/Summary/Projection contracts. A baseline/effective-value
  mismatch must invalidate evidence, not be normalized away.

## Required regression cases for the amendment

Each needs its own TEST-ID and concrete assertion before formal review:

1. Existing no-extension Context and predicates remain behavior-identical.
2. CI-MCP path gets true; neighboring MCP service retains its explicit baseline.
3. Release-only cross-cutting path evaluates correctly with zero components.
4. Non-release `.github` path is not assigned the release override.
5. Quoted true/false, null, 0/1, unknown field and missing baseline are rejected
   individually where an override requires a typed baseline/value.
6. Prefix-neighbor, traversal, case variant, symlink, excluded component path,
   stale owner/rule and overlapping/duplicate selectors each fail closed.
7. No-op true and no-op false are independently rejected.
8. A mixed two-file change cannot synthesize a match by combining properties
   across files; mixed-scope expression construction is separately rejected.
9. Deleted path, renamed path and empty change-set follow explicit A3 semantics.
10. Tampering each bound evidence field/digest is rejected independently.
11. Both trigger and conditional-facet consumers use the same scope rules.
12. Native Windows/macOS/Linux and Bash/PowerShell entry points produce the
    same canonical bytes for the same input; missing execution is not a PASS.

## Next action and limits

Ask for the option-1 scope amendment. If approved, prepare the canonical
requirements/AC/design/contracts amendment and ADR under docs/adr/ after checking
the shared numbering namespace. Expand quantifier coverage, sweep all sibling
artifacts, then run legal fresh specification and design reviews. Preserve old
FAILs and do not implement Draft tasks. ADR admission repair RT-20260908-004
affects implementation-policy review, not the specification review inputs.

No code change, test execution, review verdict, commit, push, merge or issue
closure is claimed by this proposal. PR #401 still needs the real lifecycle
reviews after its local registry correction; unchanged remote CI cannot fix it.
